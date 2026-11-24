import 'package:flutter/material.dart';

import '../components/aero_card.dart';

/// Legacy SurfaceCard deprecated in favor of [AeroCard].
///
/// Forwards directly to [AeroCard] preserving the new Aero Calm visual language.
@Deprecated('Use AeroCard instead. Deprecated for Aero Calm redesign.')
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
    return AeroCard(
      padding: padding,
      margin: margin,
      borderRadius: BorderRadius.circular(borderRadius),
      backgroundColor: backgroundColor,
      onTap: onTap,
      hoverable: hoverable,
      child: child,
    );
  }
}
