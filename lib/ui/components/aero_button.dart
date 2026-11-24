import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_density.dart';

/// Style variants for [AeroButton].
enum AeroButtonVariant { primary, tonal, ghost, danger }

/// AeroButton delivers consistent, responsive button styling across Windows and Android.
///
/// Features:
/// - Variants:
///   - [primary]: Solid violet accent
///   - [tonal]: [surface2] fill with hairline outline
///   - [ghost]: Transparent background, text only
///   - [danger]: 12% danger fill with 24% danger hairline and danger text
/// - Heights:
///   - Android (comfortable): 48 dp
///   - Windows (compact): 40 px
/// - Motion:
///   - 0.97 scale on press with linear release ([AppMotion.linear])
///   - Respects [appMotionDuration] / reduce-motion
class AeroButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final Widget? icon;
  final VoidCallback? onPressed;
  final AeroButtonVariant variant;
  final AeroDensity? density;
  final bool isLoading;
  final bool expand;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;

  const AeroButton({
    super.key,
    this.child,
    this.text,
    this.icon,
    required this.onPressed,
    this.variant = AeroButtonVariant.primary,
    this.density,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : assert(
         child != null || text != null || icon != null,
         'Provide child, text, or icon',
       );

  const AeroButton.primary({
    super.key,
    this.child,
    this.text,
    this.icon,
    required this.onPressed,
    this.density,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : variant = AeroButtonVariant.primary,
       assert(child != null || text != null || icon != null);

  const AeroButton.tonal({
    super.key,
    this.child,
    this.text,
    this.icon,
    required this.onPressed,
    this.density,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : variant = AeroButtonVariant.tonal,
       assert(child != null || text != null || icon != null);

  const AeroButton.ghost({
    super.key,
    this.child,
    this.text,
    this.icon,
    required this.onPressed,
    this.density,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : variant = AeroButtonVariant.ghost,
       assert(child != null || text != null || icon != null);

  const AeroButton.danger({
    super.key,
    this.child,
    this.text,
    this.icon,
    required this.onPressed,
    this.density,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : variant = AeroButtonVariant.danger,
       assert(child != null || text != null || icon != null);

  const AeroButton.icon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = AeroButtonVariant.tonal,
    this.density,
    this.isLoading = false,
    this.width,
    this.height,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : child = null,
       text = null,
       expand = false,
       padding = EdgeInsets.zero;

  @override
  State<AeroButton> createState() => _AeroButtonState();
}

class _AeroButtonState extends State<AeroButton> {
  bool _isPressed = false;
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails _) {
    if (_isEnabled) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveDensity = AeroDensity.resolve(context, widget.density);
    final isCompact = effectiveDensity.isCompact;

    final double defaultHeight = isCompact ? 40.0 : 48.0;
    final double effectiveHeight = widget.height ?? defaultHeight;

    final bool isIconOnly =
        widget.icon != null && widget.text == null && widget.child == null;
    final double? effectiveWidth = widget.expand
        ? double.infinity
        : (isIconOnly && widget.width == null ? effectiveHeight : widget.width);

    // Color resolution
    Color bgColor;
    Color fgColor;
    BoxBorder? border;

    switch (widget.variant) {
      case AeroButtonVariant.primary:
        if (!_isEnabled) {
          bgColor = aero.primary.withValues(alpha: 0.35);
          fgColor = aero.onSurfaceFaint;
        } else if (_isPressed) {
          bgColor = Color.lerp(aero.primary, Colors.black, 0.12)!;
          fgColor = aero.onPrimary;
        } else if (_isHovered) {
          bgColor = Color.lerp(aero.primary, Colors.white, 0.08)!;
          fgColor = aero.onPrimary;
        } else {
          bgColor = aero.primary;
          fgColor = aero.onPrimary;
        }
        break;

      case AeroButtonVariant.tonal:
        if (!_isEnabled) {
          bgColor = aero.surface2.withValues(alpha: 0.5);
          fgColor = aero.onSurfaceFaint;
          border = Border.all(color: aero.outline, width: 1.0);
        } else if (_isPressed) {
          bgColor = aero.surface3;
          fgColor = aero.onSurface;
          border = Border.all(color: aero.outlineStrong, width: 1.0);
        } else if (_isHovered) {
          bgColor = aero.surface3;
          fgColor = aero.onSurface;
          border = Border.all(color: aero.outlineStrong, width: 1.0);
        } else {
          bgColor = aero.surface2;
          fgColor = aero.onSurface;
          border = Border.all(color: aero.outline, width: 1.0);
        }
        break;

      case AeroButtonVariant.ghost:
        if (!_isEnabled) {
          bgColor = Colors.transparent;
          fgColor = aero.onSurfaceFaint;
        } else if (_isPressed) {
          bgColor = aero.surface2;
          fgColor = aero.onSurface;
        } else if (_isHovered) {
          bgColor = aero.surface2.withValues(alpha: 0.6);
          fgColor = aero.onSurface;
        } else {
          bgColor = Colors.transparent;
          fgColor = aero.onSurface;
        }
        break;

      case AeroButtonVariant.danger:
        if (!_isEnabled) {
          bgColor = aero.danger.withValues(alpha: 0.05);
          fgColor = aero.danger.withValues(alpha: 0.4);
          border = Border.all(
            color: aero.danger.withValues(alpha: 0.12),
            width: 1.0,
          );
        } else if (_isPressed) {
          bgColor = aero.danger.withValues(alpha: 0.28);
          fgColor = aero.danger;
          border = Border.all(
            color: aero.danger.withValues(alpha: 0.36),
            width: 1.0,
          );
        } else if (_isHovered) {
          bgColor = aero.danger.withValues(alpha: 0.20);
          fgColor = aero.danger;
          border = Border.all(
            color: aero.danger.withValues(alpha: 0.36),
            width: 1.0,
          );
        } else {
          bgColor = aero.danger.withValues(alpha: 0.12);
          fgColor = aero.danger;
          border = Border.all(
            color: aero.danger.withValues(alpha: 0.24),
            width: 1.0,
          );
        }
        break;
    }

    final TextStyle textStyle = TextStyle(
      fontFamily: AeroText.fontFamily,
      fontSize: isCompact ? 13 : 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: fgColor,
    );

    Widget content;
    if (widget.isLoading) {
      final double spinnerSize = isCompact ? 16 : 18;
      content = Center(
        child: SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(fgColor),
          ),
        ),
      );
    } else if (isIconOnly) {
      content = Center(
        child: IconTheme(
          data: IconThemeData(color: fgColor, size: isCompact ? 18 : 20),
          child: widget.icon!,
        ),
      );
    } else {
      final List<Widget> rowChildren = [];
      if (widget.icon != null) {
        rowChildren.add(
          IconTheme(
            data: IconThemeData(color: fgColor, size: isCompact ? 18 : 20),
            child: widget.icon!,
          ),
        );
        rowChildren.add(const SizedBox(width: 8));
      }
      if (widget.text != null) {
        rowChildren.add(
          Flexible(
            child: Text(
              widget.text!,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } else if (widget.child != null) {
        rowChildren.add(widget.child!);
      }

      content = Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rowChildren,
      );
    }

    final double horizontalPadding = isCompact ? 14.0 : 18.0;
    final effectivePadding =
        widget.padding ??
        (isIconOnly
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: horizontalPadding));

    final borderRadius = AeroRadius.mdBorderRadius;

    final duration = appMotionDuration(
      context,
      const Duration(milliseconds: 120),
    );

    final BoxBorder effectiveBorder = _isFocused
        ? Border.all(color: aero.primary, width: 2.0)
        : (border ?? const Border.fromBorderSide(BorderSide.none));

    final List<BoxShadow>? effectiveShadow = _isFocused
        ? [BoxShadow(color: aero.primaryGlow, blurRadius: 6, spreadRadius: 2)]
        : null;

    Widget button = AnimatedContainer(
      duration: duration,
      curve: Curves.linear,
      width: effectiveWidth,
      height: effectiveHeight,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: content,
    );

    // Constant-speed scale on press feedback.
    final pressDuration = appMotionDuration(context, AppMotion.fast);
    button = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: pressDuration,
      curve: _isPressed ? Curves.linear : AppMotion.linear,
      child: button,
    );

    button = FocusableActionDetector(
      enabled: _isEnabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (_isEnabled) widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: _isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: _isEnabled ? widget.onPressed : null,
          behavior: HitTestBehavior.opaque,
          child: button,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    button = Semantics(
      container: true,
      button: true,
      enabled: _isEnabled,
      label: widget.text ?? widget.tooltip,
      excludeSemantics: widget.text != null,
      child: button,
    );

    return button;
  }
}
