import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// Semantic types for [AeroSnack].
enum AeroSnackType { success, warning, danger, info, neutral }

/// Floating SnackBar helper matching the Aero design specification.
///
/// Features:
/// - Floating style with 14 px (md) border radius.
/// - Leading semantic status icon.
/// - Maximum of one trailing action button.
/// - Surface2 container with hairline border and soft shadow.
abstract final class AeroSnack {
  /// Displays a floating Aero snackbar.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AeroSnackType type = AeroSnackType.neutral,
    IconData? customIcon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.aero;

    messenger.hideCurrentSnackBar();

    final isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      padding: EdgeInsets.zero,
      duration: duration,
      content: _AeroSnackContent(
        message: message,
        type: type,
        customIcon: customIcon,
        actionLabel: actionLabel,
        onAction: onAction,
        colors: colors,
      ),
    );

    return messenger.showSnackBar(snackBar);
  }

  /// Convenience helper for success messages.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: AeroSnackType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for warning messages.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: AeroSnackType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for error / danger messages.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    return show(
      context,
      message: message,
      type: AeroSnackType.danger,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for informational messages.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: AeroSnackType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}

class _AeroSnackContent extends StatelessWidget {
  final String message;
  final AeroSnackType type;
  final IconData? customIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AeroColors colors;

  const _AeroSnackContent({
    required this.message,
    required this.type,
    this.customIcon,
    this.actionLabel,
    this.onAction,
    required this.colors,
  });

  IconData _resolveIcon() {
    if (customIcon != null) return customIcon!;
    switch (type) {
      case AeroSnackType.success:
        return Symbols.check_circle_rounded;
      case AeroSnackType.warning:
        return Symbols.warning_amber_rounded;
      case AeroSnackType.danger:
        return Symbols.error_rounded;
      case AeroSnackType.info:
        return Symbols.info_rounded;
      case AeroSnackType.neutral:
        return Symbols.notifications_none_rounded;
    }
  }

  Color _resolveIconColor() {
    switch (type) {
      case AeroSnackType.success:
        return colors.success;
      case AeroSnackType.warning:
        return colors.warning;
      case AeroSnackType.danger:
        return colors.danger;
      case AeroSnackType.info:
        return colors.info;
      case AeroSnackType.neutral:
        return colors.onSurfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _resolveIcon();
    final iconColor = _resolveIconColor();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: AeroRadius.mdBorderRadius,
            border: Border.all(color: colors.outlineStrong, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AeroSpace.lg,
            vertical: AeroSpace.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: AeroSpace.md),
              Expanded(
                child: Text(
                  message,
                  style: AeroText.bodySm.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: AeroSpace.md),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction!();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AeroSpace.sm,
                      vertical: AeroSpace.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AeroText.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
