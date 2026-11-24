import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/tool_update_provider.dart';
import '../../services/core/android_storage_service.dart';
import '../components/aero_button.dart';
import '../components/aero_density.dart';
import '../components/aero_dialog.dart';
import 'bug_report_dialog.dart';

/// Aero-styled modal dialog providing clear, human-friendly error details,
/// suggestions, actionable resolution steps, and expandable technical details.
///
/// Features (redesign_spec 7.7):
/// - Wrapped in [AeroDialog] (24 px radius xl, surface1, hairline outline).
/// - Human sentence summary + recommendation highlight.
/// - Expandable technical details with copy button and monospace font.
/// - Max 2 actions per view, primary on right, easy bug reporting.
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

    return showAeroDialog<void>(
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
        return Symbols.lock_rounded;
      case ErrorCategory.network:
        return Symbols.wifi_off_rounded;
      case ErrorCategory.fileSystem:
        return Symbols.folder_off_rounded;
      case ErrorCategory.permission:
        return Symbols.security_rounded;
      case ErrorCategory.rateLimit:
        return Symbols.speed_rounded;
      case ErrorCategory.content:
        return Symbols.videocam_off_rounded;
      case ErrorCategory.security:
        return Symbols.verified_user_rounded;
      case ErrorCategory.validation:
        return Symbols.link_off_rounded;
      case ErrorCategory.process:
        return Symbols.terminal_rounded;
      case ErrorCategory.toolUpdate:
        return Symbols.system_update_alt_rounded;
      case ErrorCategory.data:
        return Symbols.code_rounded;
      case ErrorCategory.user:
        return Symbols.cancel_rounded;
      case ErrorCategory.outdatedTool:
        return Symbols.update_rounded;
      case ErrorCategory.unknown:
        return Symbols.error_rounded;
    }
  }

  Color _colorForCategory(AeroColors colors, ErrorCategory category) {
    switch (category) {
      case ErrorCategory.rateLimit:
      case ErrorCategory.outdatedTool:
      case ErrorCategory.toolUpdate:
      case ErrorCategory.permission:
        return colors.warning;
      default:
        return colors.danger;
    }
  }

  String _categoryLabel(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return 'Login / cookies';
      case ErrorCategory.network:
      case ErrorCategory.fileSystem:
      case ErrorCategory.permission:
      case ErrorCategory.rateLimit:
      case ErrorCategory.content:
      case ErrorCategory.security:
      case ErrorCategory.validation:
      case ErrorCategory.process:
        return 'Download failed';
      case ErrorCategory.data:
        return 'Search / metadata';
      case ErrorCategory.user:
        return 'Other';
      case ErrorCategory.outdatedTool:
      case ErrorCategory.toolUpdate:
        return 'Update';
      case ErrorCategory.unknown:
        return 'Other';
    }
  }

  void _copyDetails() {
    final details =
        widget.errorHelper.technicalDetails ??
        widget.errorHelper.originalError ??
        widget.errorHelper.friendlyMessage;
    Clipboard.setData(ClipboardData(text: details));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _openBugReport() {
    final details =
        widget.errorHelper.technicalDetails ??
        widget.errorHelper.originalError ??
        widget.errorHelper.friendlyMessage;
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    showAeroDialog<void>(
      context: navigator.context,
      builder: (dialogContext) => BugReportDialog(
        initialSummary: widget.errorHelper.title,
        initialErrorDetail: details,
        initialCategory: _categoryLabel(widget.errorHelper.category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final error = widget.errorHelper;
    final categoryColor = _colorForCategory(colors, error.category);
    final isPermission = error.category == ErrorCategory.permission;
    final isOutdated =
        error.category == ErrorCategory.outdatedTool ||
        error.category == ErrorCategory.toolUpdate;

    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _iconForCategory(error.category),
          size: 22,
          color: categoryColor,
        ),
      ),
      title: Text(
        widget.customTitle ?? error.title,
        style: AeroText.title.copyWith(color: colors.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Human sentence summary
            Text(
              error.friendlyMessage,
              style: AeroText.body.copyWith(
                color: colors.onSurfaceMuted,
                height: 1.4,
              ),
            ),

            // Recommendation Card
            if (error.suggestion != null && error.suggestion!.isNotEmpty) ...[
              const SizedBox(height: AeroSpace.md),
              Container(
                padding: const EdgeInsets.all(AeroSpace.md),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: AeroRadius.mdBorderRadius,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Symbols.lightbulb_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AeroSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended Action',
                            style: AeroText.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            error.suggestion!,
                            style: AeroText.bodySm.copyWith(
                              color: colors.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Expandable technical details
            if (error.technicalDetails != null &&
                error.technicalDetails!.isNotEmpty) ...[
              const SizedBox(height: AeroSpace.md),
              InkWell(
                borderRadius: AeroRadius.smBorderRadius,
                onTap: () {
                  setState(() {
                    _showTechnicalDetails = !_showTechnicalDetails;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _showTechnicalDetails
                            ? Symbols.keyboard_arrow_down_rounded
                            : Symbols.keyboard_arrow_right_rounded,
                        size: 18,
                        color: colors.onSurfaceMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Technical Details',
                        style: AeroText.label.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                      const Spacer(),
                      AeroButton(
                        variant: AeroButtonVariant.ghost,
                        density: AeroDensity.compact,
                        text: _copied ? 'Copied' : 'Copy',
                        icon: Icon(
                          _copied
                              ? Symbols.check_rounded
                              : Symbols.content_copy_rounded,
                          size: 14,
                          color: _copied ? colors.success : null,
                        ),
                        onPressed: _copyDetails,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showTechnicalDetails) ...[
                const SizedBox(height: AeroSpace.xs),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(AeroSpace.md),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: AeroRadius.smBorderRadius,
                    border: Border.all(color: colors.outline),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error.technicalDetails!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colors.onSurfaceMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: _buildActions(isOutdated, isPermission),
    );
  }

  List<Widget> _buildActions(bool isOutdated, bool isPermission) {
    if (isOutdated) {
      return [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          isLoading: _isUpdating,
          text: _isUpdating ? 'Updating…' : 'Update yt-dlp',
          icon: const Icon(Symbols.system_update_rounded, size: 16),
          onPressed: _isUpdating
              ? null
              : () async {
                  setState(() => _isUpdating = true);
                  try {
                    final toolProvider = context.read<ToolUpdateProvider>();
                    final success = await toolProvider.updateYtdlp();
                    if (mounted) {
                      Navigator.of(context).pop();
                      if (success) {
                        widget.onRetry?.call();
                      }
                    }
                  } catch (_) {
                    if (mounted) setState(() => _isUpdating = false);
                  }
                },
        ),
      ];
    }

    if (isPermission && PlatformUtils.isAndroid) {
      return [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Open Settings',
          icon: const Icon(Symbols.settings_rounded, size: 16),
          onPressed: () async {
            Navigator.of(context).pop();
            await AndroidStorageService().openManageStorageSettings();
          },
        ),
      ];
    }

    if (widget.onRetry != null) {
      return [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Report Bug',
          icon: const Icon(Symbols.pest_control_rounded, size: 16),
          onPressed: _openBugReport,
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Retry',
          icon: const Icon(Symbols.refresh_rounded, size: 16),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRetry?.call();
          },
        ),
      ];
    }

    return [
      AeroButton(
        variant: AeroButtonVariant.ghost,
        text: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
      AeroButton(
        variant: AeroButtonVariant.tonal,
        text: 'Report Bug',
        icon: const Icon(Symbols.pest_control_rounded, size: 16),
        onPressed: _openBugReport,
      ),
    ];
  }
}
