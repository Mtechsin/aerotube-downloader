import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_density.dart';

/// AeroChip delivers clean choice and filter chips.
///
/// Features:
/// - Corner radius: [AeroRadius.sm] (10 px)
/// - Selected state: [AeroColors.primarySoft] fill + [AeroColors.primary] text & hairline
/// - Unselected state: [AeroColors.surface2] fill + [AeroColors.outline] hairline + [AeroColors.onSurface] text
/// - Smooth 120ms hover transition without layout shifts
class AeroChip extends StatefulWidget {
  final Widget? label;
  final String? text;
  final Widget? icon;
  final Widget? avatar;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool enabled;
  final AeroDensity? density;
  final EdgeInsetsGeometry? padding;

  const AeroChip({
    super.key,
    this.label,
    this.text,
    this.icon,
    this.avatar,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    this.enabled = true,
    this.density,
    this.padding,
  }) : assert(label != null || text != null, 'Provide label or text');

  @override
  State<AeroChip> createState() => _AeroChipState();
}

class _AeroChipState extends State<AeroChip> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveDensity = AeroDensity.resolve(context, widget.density);
    final isCompact = effectiveDensity.isCompact;

    final double height = isCompact ? 30.0 : 36.0;

    // Color resolution
    final Color bgColor;
    final Color fgColor;
    final BoxBorder border;

    if (!widget.enabled) {
      bgColor = aero.surface2.withValues(alpha: 0.5);
      fgColor = aero.onSurfaceFaint;
      border = Border.all(
        color: aero.outline.withValues(alpha: 0.4),
        width: 1.0,
      );
    } else if (widget.selected) {
      bgColor = _isHovered
          ? aero.primarySoft.withValues(alpha: 0.28)
          : aero.primarySoft;
      fgColor = aero.primary;
      border = Border.all(color: aero.primary, width: 1.0);
    } else {
      bgColor = _isHovered ? aero.surface3 : aero.surface2;
      fgColor = _isHovered ? aero.onSurface : aero.onSurfaceMuted;
      border = Border.all(
        color: _isHovered ? aero.outlineStrong : aero.outline,
        width: 1.0,
      );
    }

    final TextStyle textStyle = AeroText.label.copyWith(
      fontSize: isCompact ? 11.5 : 12.5,
      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
      color: fgColor,
    );

    final List<Widget> children = [];

    if (widget.avatar != null) {
      children.add(widget.avatar!);
      children.add(const SizedBox(width: 6));
    } else if (widget.icon != null) {
      children.add(
        IconTheme(
          data: IconThemeData(color: fgColor, size: isCompact ? 14 : 16),
          child: widget.icon!,
        ),
      );
      children.add(const SizedBox(width: 6));
    }

    if (widget.text != null) {
      children.add(Text(widget.text!, style: textStyle));
    } else if (widget.label != null) {
      children.add(widget.label!);
    }

    if (widget.onDeleted != null) {
      children.add(const SizedBox(width: 4));
      children.add(
        GestureDetector(
          onTap: widget.enabled ? widget.onDeleted : null,
          child: Icon(
            Symbols.close_rounded,
            size: isCompact ? 14 : 16,
            color: fgColor,
          ),
        ),
      );
    }

    final effectivePadding =
        widget.padding ??
        EdgeInsets.symmetric(horizontal: isCompact ? 10.0 : 12.0);

    final duration = appMotionDuration(
      context,
      const Duration(milliseconds: 90),
    );

    final BoxBorder effectiveBorder = _isFocused
        ? Border.all(color: aero.primary, width: 2.0)
        : border;

    final List<BoxShadow>? effectiveShadow = _isFocused
        ? [BoxShadow(color: aero.primaryGlow, blurRadius: 4, spreadRadius: 1)]
        : null;

    Widget chip = AnimatedContainer(
      duration: duration,
      curve: AppMotion.emphasized,
      height: height,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AeroRadius.smBorderRadius,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );

    if (widget.onTap != null && widget.enabled) {
      chip = FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (v) => setState(() => _isFocused = v),
        onShowHoverHighlight: (v) => setState(() => _isHovered = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: chip,
          ),
        ),
      );
    }

    chip = Semantics(
      container: true,
      button: widget.onTap != null,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.text,
      excludeSemantics: widget.text != null,
      child: chip,
    );

    return chip;
  }
}

/// FormatChip is specialized for video/audio format selection (e.g., 1080p, MP3)
/// with an optional size estimate and badge.
///
/// Features:
/// - Corner radius: [AeroRadius.sm] (10 px)
/// - Selected state: [AeroColors.primarySoft] + [AeroColors.primary] text & hairline
/// - Subtitle / size estimate uses tabular figures for jitter-free numbers
class FormatChip extends StatefulWidget {
  final String label;
  final String? sizeEstimate;
  final String? badge;
  final Widget? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final AeroDensity? density;
  final EdgeInsetsGeometry? padding;

  const FormatChip({
    super.key,
    required this.label,
    this.sizeEstimate,
    this.badge,
    this.icon,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.density,
    this.padding,
  });

  @override
  State<FormatChip> createState() => _FormatChipState();
}

class _FormatChipState extends State<FormatChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveDensity = AeroDensity.resolve(context, widget.density);
    final isCompact = effectiveDensity.isCompact;

    final hasSubtitle =
        widget.sizeEstimate != null && widget.sizeEstimate!.isNotEmpty;

    // Color resolution
    final Color bgColor;
    final Color primaryFgColor;
    final Color secondaryFgColor;
    final BoxBorder border;

    if (!widget.enabled) {
      bgColor = aero.surface2.withValues(alpha: 0.5);
      primaryFgColor = aero.onSurfaceFaint;
      secondaryFgColor = aero.onSurfaceFaint;
      border = Border.all(
        color: aero.outline.withValues(alpha: 0.4),
        width: 1.0,
      );
    } else if (widget.selected) {
      bgColor = _isHovered
          ? aero.primarySoft.withValues(alpha: 0.28)
          : aero.primarySoft;
      primaryFgColor = aero.primary;
      secondaryFgColor = aero.primary.withValues(alpha: 0.85);
      border = Border.all(color: aero.primary, width: 1.0);
    } else {
      bgColor = _isHovered ? aero.surface3 : aero.surface2;
      primaryFgColor = _isHovered ? aero.onSurface : aero.onSurfaceMuted;
      secondaryFgColor = aero.onSurfaceFaint;
      border = Border.all(
        color: _isHovered ? aero.outlineStrong : aero.outline,
        width: 1.0,
      );
    }

    final TextStyle labelStyle = AeroText.label.copyWith(
      fontSize: isCompact ? 12 : 13,
      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
      color: primaryFgColor,
    );

    final TextStyle subStyle = AeroText.caption.withTabularFigures().copyWith(
      fontSize: isCompact ? 10 : 11,
      color: secondaryFgColor,
    );

    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(
              color: primaryFgColor,
              size: isCompact ? 14 : 16,
            ),
            child: widget.icon!,
          ),
          const SizedBox(width: 6),
        ],
        Text(widget.label, style: labelStyle),
        if (widget.badge != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: widget.selected
                  ? aero.primary.withValues(alpha: 0.2)
                  : aero.surface3,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.badge!,
              style: TextStyle(
                fontFamily: AeroText.fontFamily,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: primaryFgColor,
              ),
            ),
          ),
        ],
      ],
    );

    Widget content;
    if (hasSubtitle) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          labelRow,
          const SizedBox(height: 2),
          Text(widget.sizeEstimate!, style: subStyle),
        ],
      );
    } else {
      content = labelRow;
    }

    final double minHeight = hasSubtitle
        ? (isCompact ? 44.0 : 48.0)
        : (isCompact ? 30.0 : 36.0);

    final effectivePadding =
        widget.padding ??
        EdgeInsets.symmetric(
          horizontal: isCompact ? 12.0 : 14.0,
          vertical: hasSubtitle ? 6.0 : (isCompact ? 6.0 : 8.0),
        );

    final duration = appMotionDuration(
      context,
      const Duration(milliseconds: 90),
    );

    Widget chip = AnimatedContainer(
      duration: duration,
      curve: AppMotion.emphasized,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AeroRadius.smBorderRadius,
        border: border,
      ),
      child: Center(widthFactor: 1, child: content),
    );

    if (widget.onTap != null && widget.enabled) {
      chip = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: chip,
        ),
      );
    }

    return chip;
  }
}
