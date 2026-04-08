import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/utils/platform_utils.dart';

/// Mobile-optimized glass card with performance considerations
/// Uses simpler effects on mobile for better performance
class MobileGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final Border? border;
  final double? opacity;
  final Color? borderColor;
  final VoidCallback? onTap;

  const MobileGlassCard({
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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = PlatformUtils.isMobile;

    // On mobile, use simpler effect without BackdropFilter for performance
    if (isMobile) {
      return _buildMobileCard(context, isDark);
    }

    // On desktop, use full glass-morphism effect
    return _buildDesktopCard(context, isDark);
  }

  Widget _buildDesktopCard(BuildContext context, bool isDark) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor ??
                    (isDark
                        ? Colors.white.withValues(alpha: opacity ?? 0.05)
                        : Colors.white.withValues(alpha: opacity ?? 0.7)),
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                    Border.all(
                      color: borderColor ??
                          (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.3)),
                      width: 1,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, bool isDark) {
    // Use simpler container without BackdropFilter for mobile performance
    return Container(
      margin: margin,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Gradient to simulate glass effect without blur
            gradient: backgroundColor != null
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark
                          ? Colors.white.withValues(alpha: (opacity ?? 0.05) + 0.05)
                          : Colors.white.withValues(alpha: (opacity ?? 0.7) - 0.1),
                      isDark
                          ? Colors.white.withValues(alpha: (opacity ?? 0.05))
                          : Colors.white.withValues(alpha: (opacity ?? 0.7) - 0.15),
                    ],
                  ),
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: borderColor ??
                      (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.3)),
                  width: 1,
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Mobile-optimized surface card without glass effects
class MobileSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool elevation;

  const MobileSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.onTap,
    this.elevation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: elevation
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
