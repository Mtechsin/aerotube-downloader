import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../components/aero_button.dart';
import '../components/aero_dialog.dart';
import '../../services/core/logging_service.dart';

/// Developer logs viewer widget
class LogsViewer extends StatelessWidget {
  final bool showTitle;

  const LogsViewer({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final service = LoggingService();

    return StreamBuilder<List<LogEntry>>(
      stream: service.devLogsStream,
      initialData: service.devLogs,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? service.devLogs;

        return Column(
          children: [
            // Header with actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (showTitle) ...[
                    Icon(
                      Symbols.bug_report_rounded,
                      color: context.aero.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Developer Logs',
                      style: AeroText.titleSm.copyWith(
                        color: context.aero.onSurface,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${logs.length} entries',
                    style: AeroText.caption.copyWith(
                      color: context.aero.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Symbols.content_copy_rounded, size: 18),
                    onPressed: () {
                      final text = LoggingService().exportLogs();
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                        ),
                      );
                    },
                    tooltip: 'Copy all logs',
                  ),
                  IconButton(
                    icon: const Icon(Symbols.clear_all_rounded, size: 18),
                    onPressed: () async {
                      // H20: confirm before wiping developer logs.
                      final entryCount = service.devLogs.length;
                      final aero = context.aero;
                      final confirmed = await showAeroDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AeroDialog(
                          titleText: 'Clear logs?',
                          content: Text(
                            'Remove all $entryCount developer log entries? '
                            'This cannot be undone.',
                            style: AeroText.body.copyWith(
                              color: aero.onSurfaceMuted,
                            ),
                          ),
                          actions: [
                            AeroButton(
                              variant: AeroButtonVariant.ghost,
                              text: 'Cancel',
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                            ),
                            AeroButton(
                              variant: AeroButtonVariant.danger,
                              text: 'Clear',
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      LoggingService().clearDevLogs();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Developer logs cleared')),
                      );
                    },
                    tooltip: 'Clear logs',
                  ),
                ],
              ),
            ),

            // Logs list
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.check_circle_rounded,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs yet',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[logs.length - 1 - index];
                        return _LogEntryCard(log: log);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact inline preview for recent developer logs.
class RecentLogsPreview extends StatelessWidget {
  final VoidCallback onViewAll;

  const RecentLogsPreview({super.key, required this.onViewAll});

  Color _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  String _truncateMessage(String message) {
    const maxLength = 60;
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    final service = LoggingService();

    return StreamBuilder<List<LogEntry>>(
      stream: service.devLogsStream,
      initialData: service.devLogs,
      builder: (context, snapshot) {
        final logs = service.isEnabled
            ? (snapshot.data ?? service.devLogs).reversed.take(5).toList()
            : const <LogEntry>[];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Symbols.receipt_long_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Logs',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View All ->'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.check_circle_rounded,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No recent log entries',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: logs.map((log) {
                    final levelColor = _colorForLevel(log.level);
                    final component = log.component;
                    final message = _truncateMessage(log.message);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: levelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '[${log.compactTimestamp}]'
                              '${component != null && component.isNotEmpty ? ' [$component]' : ''} '
                              '$message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  final LogEntry log;

  const _LogEntryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final Color levelColor;
    switch (log.level) {
      case LogLevel.debug:
        levelColor = colors.onSurfaceMuted;
        break;
      case LogLevel.info:
        levelColor = colors.info;
        break;
      case LogLevel.warning:
        levelColor = colors.warning;
        break;
      case LogLevel.error:
        levelColor = colors.danger;
        break;
    }

    final backgroundColor = switch (log.level) {
      LogLevel.error => colors.danger.withValues(alpha: 0.07),
      LogLevel.warning => colors.warning.withValues(alpha: 0.07),
      _ => colors.surface2,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AeroSpace.sm),
      padding: const EdgeInsets.all(AeroSpace.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AeroRadius.mdBorderRadius,
        border: Border.all(color: levelColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: levelColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.formattedTimestamp,
                style: AeroText.mono.copyWith(
                  color: colors.onSurfaceMuted,
                  fontSize: 11,
                ),
              ),
              if (log.component != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.2),
                    borderRadius: AeroRadius.xsBorderRadius,
                  ),
                  child: Text(
                    log.component!,
                    style: AeroText.caption.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            log.message,
            style: AeroText.bodySm.copyWith(color: colors.onSurface),
          ),
          if (log.error != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              'Error: ${log.error}',
              style: AeroText.mono.copyWith(fontSize: 11, color: colors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
