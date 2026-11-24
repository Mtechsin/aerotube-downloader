import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';

/// A standard settings row with an icon in a 36 px rounded square,
/// title, optional subtitle, and trailing control or navigation chevron.
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;
  final EdgeInsetsGeometry? padding;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final isInteractive = enabled && onTap != null;

    final effectiveVerticalPadding = dense ? AeroSpace.sm : AeroSpace.md;
    final effectiveHorizontalPadding = dense ? AeroSpace.md : AeroSpace.lg;
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          vertical: effectiveVerticalPadding,
          horizontal: effectiveHorizontalPadding,
        );

    Widget? leading = iconWidget;
    if (leading == null && icon != null) {
      leading = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: AeroRadius.smBorderRadius,
          border: Border.all(color: colors.outline, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? (iconColor ?? colors.onSurface)
              : colors.onSurfaceFaint,
        ),
      );
    }

    Widget? trailingWidget = trailing;
    if (trailingWidget == null && isInteractive) {
      trailingWidget = Icon(
        Symbols.chevron_right_rounded,
        size: 20,
        color: colors.onSurfaceMuted,
      );
    }

    final titleWidget = Text(
      title,
      style: AeroText.body.copyWith(
        color: enabled ? colors.onSurface : colors.onSurfaceFaint,
        fontWeight: FontWeight.w600,
      ),
      maxLines: PlatformUtils.isMobile ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );

    final subtitleWidget = (subtitle != null && subtitle!.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: AeroText.bodySm.copyWith(
                color: enabled ? colors.onSurfaceMuted : colors.onSurfaceFaint,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    Widget rowContent = Padding(
      padding: effectivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading,
            SizedBox(
              width: PlatformUtils.isMobile ? AeroSpace.sm : AeroSpace.md,
            ),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                if (subtitleWidget != null) subtitleWidget,
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            SizedBox(
              width: PlatformUtils.isMobile ? AeroSpace.sm : AeroSpace.md,
            ),
            trailingWidget,
          ],
        ],
      ),
    );

    if (isInteractive) {
      rowContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AeroRadius.smBorderRadius,
          hoverColor: colors.surface3.withValues(alpha: 0.4),
          splashColor: colors.primarySoft,
          highlightColor: colors.surface2,
          child: rowContent,
        ),
      );
    }

    return Semantics(
      button: isInteractive,
      enabled: enabled,
      label: subtitle != null ? '$title, $subtitle' : title,
      child: rowContent,
    );
  }
}
