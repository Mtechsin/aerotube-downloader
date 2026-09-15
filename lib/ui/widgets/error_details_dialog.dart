import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../services/core/android_storage_service.dart';
import '../../providers/tool_update_provider.dart';
import 'bug_report_dialog.dart';

/// Modal dialog providing clear, human-friendly error details,
/// suggestions, and actionable resolution steps.
class ErrorDetailsDialog extends StatefulWidget {
  final ErrorHelper errorHelper;
  final VoidCallback? onRetry;
  final String? customTitle;

  const ErrorDetailsDialog({
    super.key,
    required this.errorHelper,
    this.onRetry,
    this.customTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required dynamic error,
    VoidCallback? onRetry,
    String? customTitle,
  }) {
    final helper = error is ErrorHelper
        ? error
        : ErrorHelper.parse(error.toString());

    return showDialog<void>(
      context: context,
      builder: (context) => ErrorDetailsDialog(
        errorHelper: helper,
        onRetry: onRetry,
        customTitle: customTitle,
      ),
    );
  }

  @override
  State<ErrorDetailsDialog> createState() => _ErrorDetailsDialogState();
}

class _ErrorDetailsDialogState extends State<ErrorDetailsDialog> {
  bool _showTechnicalDetails = false;
  bool _copied = false;
  bool _isUpdating = false;

  IconData _iconForCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return Icons.lock_outline_rounded;
      case ErrorCategory.network:
        return Icons.wifi_off_rounded;
      case ErrorCategory.fileSystem:
        return Icons.folder_off_rounded;
      case ErrorCategory.permission:
        return Icons.security_rounded;
      case ErrorCategory.rateLimit:
        return Icons.speed_rounded;
      case ErrorCategory.content:
        return Icons.videocam_off_rounded;
      case ErrorCategory.security:
        return Icons.verified_user_outlined;
      case ErrorCategory.validation:
        return Icons.link_off_rounded;
      case ErrorCategory.process:
        return Icons.terminal_rounded;
      case ErrorCategory.toolUpdate:
        return Icons.system_update_alt_rounded;
      case ErrorCategory.data:
        return Icons.code_rounded;
      case ErrorCategory.user:
        return Icons.cancel_outlined;
      case ErrorCategory.outdatedTool:
        return Icons.update_rounded;
      case ErrorCategory.unknown:
        return Icons.error_outline_rounded;
    }
  }

  Color _colorForCategory(ThemeData theme, ErrorCategory category) {
    switch (category) {
      case ErrorCategory.rateLimit:
      case ErrorCategory.outdatedTool:
        return Colors.orange;
      case ErrorCategory.permission:
        return Colors.amber.shade700;
      default:
        return theme.colorScheme.error;
    }
  }

  String _categoryLabel(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return 'Login / cookies';
      case ErrorCategory.network:
        return 'Download failed';
      case ErrorCategory.fileSystem:
        return 'Download failed';
      case ErrorCategory.permission:
        return 'Download failed';
      case ErrorCategory.rateLimit:
        return 'Download failed';
      case ErrorCategory.content:
        return 'Download failed';
      case ErrorCategory.security:
        return 'Download failed';
      case ErrorCategory.validation:
        return 'Download failed';
      case ErrorCategory.process:
        return 'Download failed';
      case ErrorCategory.data:
        return 'Search / metadata';
      case ErrorCategory.user:
        return 'Other';
      case ErrorCategory.outdatedTool:
        return 'Update';
      case ErrorCategory.toolUpdate:
        return 'Update';
      case ErrorCategory.unknown:
        return 'Other';
    }
  }

  void _copyDetails() {
    final details = widget.errorHelper.technicalDetails ??
        widget.errorHelper.originalError ??
        widget.errorHelper.friendlyMessage;
    Clipboard.setData(ClipboardData(text: details));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = widget.errorHelper;
    final categoryColor = _colorForCategory(theme, error.category);
    final isPermission = error.category == ErrorCategory.permission;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header icon & title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForCategory(error.category),
                        size: 28,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customTitle ?? error.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error.friendlyMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Recommendation Card
                if (error.suggestion != null && error.suggestion!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recommended Action',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                error.suggestion!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Technical details collapsible section
                if (error.technicalDetails != null &&
                    error.technicalDetails!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _showTechnicalDetails = !_showTechnicalDetails;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _showTechnicalDetails
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Technical Details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _copyDetails,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 14,
                              color: _copied ? Colors.green : null,
                            ),
                            label: Text(
                              _copied ? 'Copied' : 'Copy',
                              style: TextStyle(
                                fontSize: 11,
                                color: _copied ? Colors.green : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showTechnicalDetails) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          error.technicalDetails!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (error.category == ErrorCategory.outdatedTool ||
                        error.category == ErrorCategory.toolUpdate)
                      FilledButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () async {
                                setState(() => _isUpdating = true);
                                try {
                                  final toolProvider =
                                      context.read<ToolUpdateProvider>();
                                  final success =
                                      await toolProvider.updateYtdlp();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    if (success) {
                                      widget.onRetry?.call();
                                    }
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => _isUpdating = false);
                                  }
                                }
                              },
                        icon: _isUpdating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.system_update_rounded, size: 18),
                        label: Text(
                          _isUpdating ? 'Updating yt-dlp...' : 'Update yt-dlp Now',
                        ),
                      ),
                    if (isPermission && PlatformUtils.isAndroid)
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await AndroidStorageService()
                              .openManageStorageSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('Open Settings'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (widget.onRetry != null)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onRetry!();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final details = error.technicalDetails ??
                            error.originalError ??
                            error.friendlyMessage;
                        final navigator = Navigator.of(
                          context,
                          rootNavigator: true,
                        );
                        navigator.pop();
                        showDialog<void>(
                          context: navigator.context,
                          builder: (dialogContext) => BugReportDialog(
                            initialSummary: error.title,
                            initialErrorDetail: details,
                            initialCategory: _categoryLabel(error.category),
                          ),
                        );
                      },
                      icon: const Icon(Icons.pest_control_rounded, size: 16),
                      label: const Text('Report'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}