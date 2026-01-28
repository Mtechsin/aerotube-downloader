import 'package:flutter/material.dart';
import 'dart:ui';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final Border? border;
  final double? opacity;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.blur = 10,
    this.border,
    this.opacity,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? 
                  (isDark 
                      ? Colors.white.withValues(alpha:opacity ?? 0.05)
                      : Colors.white.withValues(alpha:opacity ?? 0.7)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: borderColor ?? (isDark 
                    ? Colors.white.withValues(alpha:0.1)
                    : Colors.white.withValues(alpha:0.3)),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hoverable;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.onTap,
    this.hoverable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha:0.1),
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null || hoverable) {
      return _HoverableCard(
        onTap: onTap,
        borderRadius: borderRadius,
        child: card,
      );
    }

    return card;
  }
}

class _HoverableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _HoverableCard({
    required this.child,
    this.onTap,
    required this.borderRadius,
  });

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(_isHovered ? 1.02 : 1.0, _isHovered ? 1.02 : 1.0, 1.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isHovered ? 0.9 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
