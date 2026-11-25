import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';

/// AeroCard delivers layered tonal depth ("Aero Calm") without box shadows.
///
/// Features:
/// - Background: [AeroColors.surface1]
/// - Border: Hairline [AeroColors.outline]
/// - Corner radius: [AeroRadius.lg] (18 px)
/// - Optional hover: Smooth tonal shift from [surface1] -> [surface3] over 120ms
///   without layout-shifting scale changes.
/// - Optional selected: [AeroColors.primarySoft] background with [AeroColors.primary] hairline.
class AeroCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Border? border;
  final bool selected;
  final bool hoverable;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  const AeroCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.border,
    this.selected = false,
    this.hoverable = false,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  State<AeroCard> createState() => _AeroCardState();
}

class _AeroCardState extends State<AeroCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveRadius = widget.borderRadius ?? AeroRadius.lgBorderRadius;

    // Background color resolution
    final Color effectiveBg;
    if (widget.selected) {
      effectiveBg = aero.primarySoft;
    } else if (widget.backgroundColor != null) {
      effectiveBg = _isHovered && widget.hoverable
          ? Color.lerp(widget.backgroundColor, aero.surface3, 0.5)!
          : widget.backgroundColor!;
    } else {
      effectiveBg = _isHovered && widget.hoverable
          ? aero.surface3
          : aero.surface1;
    }

    // Border resolution
    final BoxBorder effectiveBorder;
    if (widget.border != null) {
      effectiveBorder = widget.border!;
    } else if (widget.selected) {
      effectiveBorder = Border.all(color: aero.primary, width: 1.0);
    } else if (widget.borderColor != null) {
      effectiveBorder = Border.all(color: widget.borderColor!, width: 1.0);
    } else {
      effectiveBorder = Border.all(
        color: _isHovered && widget.hoverable
            ? aero.outlineStrong
            : aero.outline,
        width: 1.0,
      );
    }

    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    Widget content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(AeroSpace.lg),
      child: widget.child,
    );

    if (isInteractive) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: effectiveRadius,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: content,
        ),
      );
    }

    final decoration = BoxDecoration(
      color: effectiveBg,
      borderRadius: effectiveRadius,
      border: effectiveBorder,
    );

    // Static cards avoid AnimatedContainer's AnimationController/tween overhead.
    if (!widget.hoverable && !widget.selected && !isInteractive) {
      return Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        clipBehavior: widget.clipBehavior,
        decoration: decoration,
        child: content,
      );
    }

    final duration = appMotionDuration(
      context,
      const Duration(milliseconds: 90),
    );

    final card = AnimatedContainer(
      duration: duration,
      curve: AppMotion.emphasized,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      clipBehavior: widget.clipBehavior,
      decoration: decoration,
      child: content,
    );

    if (!widget.hoverable && !isInteractive) {
      return card;
    }

    return MouseRegion(
      onEnter: widget.hoverable
          ? (_) => setState(() => _isHovered = true)
          : null,
      onExit: widget.hoverable
          ? (_) => setState(() => _isHovered = false)
          : null,
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      child: card,
    );
  }
}
