import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// Semantic status types for [StatusPill].
enum StatusPillType { success, warning, danger, info, neutral }

/// A compact, rounded indicator pill displaying semantic status.
///
/// Features:
/// - Semantic coloring with 12% tinted fill and 24% hairline border.
/// - Optional status dot indicator or spinning loader.
/// - Optional leading or trailing icons.
/// - Optional [onTap] callback with interactive ripple and pointer feedback.
class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillType type;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool showDot;
  final bool showSpinner;
  final VoidCallback? onTap;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusPillType.neutral,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  });

  /// Factory helper for a success pill.
  const StatusPill.success({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  }) : type = StatusPillType.success;

  /// Factory helper for a warning pill.
  const StatusPill.warning({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  }) : type = StatusPillType.warning;

  /// Factory helper for a danger/error pill.
  const StatusPill.danger({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  }) : type = StatusPillType.danger;

  /// Factory helper for an info pill.
  const StatusPill.info({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  }) : type = StatusPillType.info;

  /// Factory helper for a neutral pill.
  const StatusPill.neutral({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.showDot = false,
    this.showSpinner = false,
    this.onTap,
    this.tooltip,
    this.padding,
  }) : type = StatusPillType.neutral;

  Color _resolveTypeColor(AeroColors colors) {
    switch (type) {
      case StatusPillType.success:
        return colors.success;
      case StatusPillType.warning:
        return colors.warning;
      case StatusPillType.danger:
        return colors.danger;
      case StatusPillType.info:
        return colors.info;
      case StatusPillType.neutral:
        return colors.onSurfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final typeColor = _resolveTypeColor(colors);

    final fillColor = typeColor.withValues(alpha: 0.12);
    final borderColor = typeColor.withValues(alpha: 0.24);
    final isInteractive = onTap != null;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && icon != null) {
      leadingWidget = Icon(icon, size: 14, color: typeColor);
    } else if (leadingWidget == null && showSpinner) {
      leadingWidget = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(typeColor),
        ),
      );
    } else if (leadingWidget == null && showDot) {
      leadingWidget = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
      );
    }

    Widget pillContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leadingWidget != null) ...[
          leadingWidget,
          const SizedBox(width: AeroSpace.xs + 2),
        ],
        Text(
          label,
          style: AeroText.label.copyWith(
            color: typeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AeroSpace.xs + 2),
          trailing!,
        ],
      ],
    );

    final effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AeroSpace.sm + 2,
          vertical: AeroSpace.xs,
        );

    Widget pill = Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: AeroRadius.fullBorderRadius,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: effectivePadding,
      child: pillContent,
    );

    if (isInteractive) {
      pill = Material(
        color: Colors.transparent,
        borderRadius: AeroRadius.fullBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AeroRadius.fullBorderRadius,
          splashColor: typeColor.withValues(alpha: 0.16),
          highlightColor: typeColor.withValues(alpha: 0.08),
          child: pill,
        ),
      );
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      pill = Tooltip(message: tooltip!, child: pill);
    }

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      label: label,
      child: pill,
    );
  }
}
